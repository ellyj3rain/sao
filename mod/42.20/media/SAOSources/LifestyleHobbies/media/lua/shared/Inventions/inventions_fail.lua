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

LSInv = LSInv or {}

------------ 

local function doNote(character, text, texture, addW)
	 -- Player, Text, Type, Texture, ScreenTime, ClosePermanent, InfoPanel, NoSpam, Texture Properties
	LSNoteMng.addToQueue(getCore():getScreenWidth()-(400+addW),(getCore():getScreenHeight()/5)-50,300+addW,50, {character, text, false, texture, 5, false, false, false, {6,10,30}})
end

LSInv.OnCritFailPowerAxe = function(character, item, invData)
	LSUtil.playSoundCharacter(character, "Explosion_Small", nil, nil, true, nil, nil,{40, 60})
	local gloves = character:getClothingItem_Hands()
	local dmgHandsChance = 3
	if gloves and ZombRand(dmgHandsChance) == 0 then -- pierced gloves
		dmgHandsChance = 10
		LSUtil.deleteItemOnChar(character, gloves)
	end
	if dmgHandsChance > 0 and ZombRand(dmgHandsChance) == 0 then	
		local bd = character:getBodyDamage()
		local parts = {bd:getBodyPart(BodyPartType.Hand_L), bd:getBodyPart(BodyPartType.Hand_R)}
		for n=1,#parts do
			local part = parts[n]
			if part and not part:scratched() and ZombRand(2) == 0 then
				part:setScratched(true, true)
				if ZombRand(5) == 0 then
					part:setHaveGlass(true)
				end
			end
			if part and not part:isBurnt() and ZombRand(5) == 0 then
				part:setBurned()
				part:setBurnTime(ZombRand(5,15))
				part:setNeedBurnWash(true)
			end
		end
	end
	invData['power'][1] = 10
	LSUtil.breakInventionItem(character, item, invData)
end

LSInv.OnFailPowerAxe = function(character, item, invData)
	invData['power'][1] = 10
	LSUtil.breakInventionItem(character, item, invData)
end

LSInv.OnFailHarvester = function(character, item, invData)
	LSUtil.playSoundCharacter(character, "Steam_BurstLong", nil, nil, true, nil, nil, nil) -- character, soundName, soundVar, loopMins, transmit, proxy, soundArgs, noiseArgs
	LSUtil.doInvCooldown(item, invData)
	LSSync.transmit(item)
end

LSInv.OnCritFailHarvester = function(character, item, invData)
	LSUtil.playSoundCharacter(character, "Gadget_Break", nil, nil, true, nil, nil, nil)
	LSUtil.doInvCooldown(item, invData)
	LSUtil.breakInventionItem(character, item, invData)
end

LSInv.OnFailFoodSynthesizer = function(character, inv, invData)
	invData['foodReady'] = {1,"Lifestyle.PasteRuined"}

end

LSInv.OnCritFailFoodSynthesizer = function(character, inv, invData)
	invData['foodReady'] = false
	LSInv.breakInv(character, inv, invData)
end

LSInv.OnFailNeuralHat = function(character, charData, neuralItem)
	charData.LSMoodles["NeuralHat"].Value = 0
	neuralItem.data['recentActive'] = 0
	local soundName = "FortuneTeller_PowerDown"
	local noteText = " <RGB:1,0.2,0.2><CENTRE><SIZE:medium>"..getText("IGUI_Inventions_Bad_Roll",neuralItem.headgear:getName()).." <LEFT>"
	local noteTex = "media/ui/gearsBAD_icon.png"
	-- if battery < 50% then it just breaks
	local halfBattery = neuralItem.data['fuelUses'] < neuralItem.data['fuelContainer'][1]/2
	local choice = (halfBattery and 3) or LSUtil.rdm_inst:random(4)
	
	if choice == 1 then
		-- negative state
		LSUtil.changeTexture_Item(character, neuralItem.headgear, 2)
		charData.LSMoodles["Dunce"].Value = 1
		soundName = "Gadget_MALFUNCTION"
		noteTex = "media/ui/moodles/Dunce.png"
		noteText = noteText.." <LINE><RGB:1.0,0.6,0.6>"..getText("IGUI_Inventions_Bad_Dunce")
	else
		-- off (for all besides n state)
		LSUtil.changeTexture_Item(character, neuralItem.headgear, 0)
		neuralItem.data['running'] = false
		if choice == 2 then
			-- drain battery
			neuralItem.data['fuelUses'] = 0
			noteText = noteText.." <LINE><RGB:1.0,0.6,0.6>"..getText("IGUI_Inventions_Bad_Drain")
		elseif choice == 3 then
			-- break
			neuralItem.data['isBroken'] = true
			soundName = "MACHINE_BREAK"
			noteText = noteText.." <LINE><RGB:1.0,0.6,0.6>"..getText("IGUI_Inventions_Bad_Break")
		else
			-- cooldown
			LSUtil.doInvCooldown(neuralItem.headgear, neuralItem.data)
			noteText = noteText.." <LINE><RGB:1.0,0.6,0.6>"..getText("IGUI_Inventions_Bad_Cooldown")
		end
	end
	--
	noteText = noteText.." <LINE><RGB:0.8,0.8,0.8><CENTRE>"..getText("IGUI_Inventions_DurabilityAdvice")
	doNote(character, noteText, noteTex, 50)
	character:getEmitter():playSound(soundName)
	LSInv.doDataTransmit(neuralItem.headgear, neuralItem.data)
	LSSync.updateClientData(character, charData)
end

LSInv.OnCritFailNeuralHat = function(character, charData, neuralItem)
	charData.LSMoodles["NeuralHat"].Value = 0
	neuralItem.data['recentActive'] = 0
	local noteTex = "media/ui/gearsBAD_icon.png"
	local noteText = " <RGB:1,0.2,0.2><CENTRE><SIZE:medium>"..getText("IGUI_Inventions_Bad_RollCrit",neuralItem.headgear:getName()).." <LEFT>"
	local soundAfter, soundName = false, "MACHINE_BREAK"
	local choice = LSUtil.rdm_inst:random(2)
	
	-- off (always)
	LSUtil.changeTexture_Item(character, neuralItem.headgear, 0)
	neuralItem.data['running'] = false
	-- drain battery (always)
	neuralItem.data['fuelUses'] = 0
	-- break (always)
	neuralItem.data['isBroken'] = true
	-- cooldown (always)
	LSUtil.doInvCooldown(neuralItem.headgear, neuralItem.data)
	--
	noteText = noteText.." <LINE><RGB:1.0,0.6,0.6> - "..getText("IGUI_Inventions_Bad_Break").." <LINE> - "..getText("IGUI_Inventions_Bad_Drain").." <LINE> - "..getText("IGUI_Inventions_Bad_Cooldown")
	if choice == 1 then
		-- lingering dunce
		charData.LSMoodles["Dunce"].Value = 1
		getSoundManager():playUISound("UI_sting_confusion")
		noteTex = "media/ui/moodles/Dunce.png"
		noteText = noteText.." <LINE> - "..getText("IGUI_Inventions_Bad_Dunce")
	else
		-- burn baby burn
		LSUtil.makeCharExplode(character, {{4,false,10},1,2,{"Head","Torso_Upper"}})
		soundAfter, soundName = "MACHINE_BREAK", "Shock_SHORT"
		noteText = noteText.." <LINE> - "..getText("IGUI_Inventions_Bad_Burn")
	end
	--
	
	noteText = noteText.." <LINE><RGB:0.8,0.8,0.8><CENTRE>"..getText("IGUI_Inventions_DurabilityAdvice")
	doNote(character, noteText, noteTex, 50)
	LSInv.doDataTransmit(neuralItem.headgear, neuralItem.data)
	LSSync.updateClientData(character, charData)
	LSUtil.playSoundCharacter(character, soundName, nil, nil, nil, nil, {false, false, soundAfter})
end