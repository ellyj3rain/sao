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

LS_DJBooth = LS_DJBooth or {}
LS_DJBooth.buttons = LS_DJBooth.buttons or {}

LS_DJBooth.keyPress = function(keyNum)
	if not LS_DJBooth.isPlaying and (not LS_DJBooth.loopBeat or not LS_DJBooth.loopBeat ~= 0) then return; end
	local player = getPlayer()
	local playerNum = player and player:getPlayerNum()
	local character = playerNum and getSpecificPlayer(playerNum)
	if not character then return; end
	if not LS_DJBooth.isPlaying or LS_DJBooth.failstate or (keyNum and keyNum == 41) then
		if LS_DJBooth.loopBeat and LS_DJBooth.loopBeat ~= 0 then character:getEmitter():stopSound(LS_DJBooth.loopBeat); LS_DJBooth.loopBeat = 0; end
		return
	end
	if not keyNum or not LS_DJBooth.soundboard[keyNum] then return; end

	local musicLevel = character:getPerkLevel(Perks.Music)
	local soundKey = LS_DJBooth.soundboard[keyNum]
	local isShift = soundKey.holdShift ~= "" and ((isKeyDown(54) or isKeyDown(42)) or (LS_DJBooth.buttons.switch and soundKey.switch and LS_DJBooth.buttons.switch[soundKey.switch]))

	local soundArg = (isShift and soundKey.holdShift) or soundKey.mainKeys
	if not soundArg or soundArg == "" then return; end

	local variations = LS_DJBooth.soundKeys[soundArg]
	if variations then
		local num = LSUtil.rdm_inst:random(variations)
		soundArg = soundArg..tostring(num)
	end
	
	if isShift then
		if LS_DJBooth.loopBeat and LS_DJBooth.loopBeat ~= 0 then character:getEmitter():stopSound(LS_DJBooth.loopBeat); end
		LS_DJBooth.loopBeat = character:getEmitter():playSound(soundArg)
	else
		getSoundManager():PlayWorldSound(soundArg, character:getSquare(), 1, 5, 1, false)
	end

end

local function djBind_event()
	if not LS_DJBooth.event then
		LS_DJBooth.event = true
		Events.OnKeyStartPressed.Add(LS_DJBooth.keyPress)
	end
end

Events.OnCreatePlayer.Add(djBind_event)